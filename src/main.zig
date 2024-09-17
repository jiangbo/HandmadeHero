const std = @import("std");
const win32 = @import("win32");
const game = @import("handmade.zig");
const input = @import("input.zig");

pub const UNICODE: bool = true;

var allocator: std.mem.Allocator = undefined;
const WIDTH: i32 = 1280;
const HEIGHT: i32 = 720;

var globalRunning: bool = true;
var globalPause: bool = false;

var windowWidth: i32 = 0;
var windowHeight: i32 = 0;
var screenBuffer: win32ScreenBuffer = .{};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    allocator = gpa.allocator();

    createWindow();
    screenBuffer.deinit();
}

const win32ScreenBuffer = struct {
    info: win32.graphics.gdi.BITMAPINFO = undefined,
    memory: ?[]game.Color = null,
    width: i32 = WIDTH,
    height: i32 = HEIGHT,

    pub fn deinit(self: *win32ScreenBuffer) void {
        if (self.memory) |memory| allocator.free(memory);
    }
};

fn createWindow() void {
    var class = std.mem.zeroes(win32.ui.windows_and_messaging.WNDCLASSW);
    class.style = .{ .OWNDC = 1, .HREDRAW = 1, .VREDRAW = 1 };
    class.lpfnWndProc = mainWindowCallback;
    class.hInstance = win32.system.library_loader.GetModuleHandle(null);
    class.lpszClassName = win32.zig.L("Handmade Hero");

    if (win32.ui.windows_and_messaging.RegisterClassW(&class) == 0) {
        win32ErrorPanic();
    }

    var style = win32.ui.windows_and_messaging.WS_OVERLAPPEDWINDOW;
    style.VISIBLE = 1;
    const default = win32.ui.windows_and_messaging.CW_USEDEFAULT;
    const window = win32.ui.windows_and_messaging.CreateWindowEx(.{}, //
        class.lpszClassName, win32.zig.L("手工英雄"), //
        style, default, default, WIDTH, HEIGHT, //
        null, null, class.hInstance, null);

    const monitorRefreshHz: u32 = 60;
    const gameUpdateHz: u32 = monitorRefreshHz / 2;
    const targetNanoPerFrame: u64 = std.time.ns_per_s / gameUpdateHz;

    if (window == null) win32ErrorPanic();
    createDIBSection();

    var soundOutput = Win32SoundOutput{};
    const samples = soundOutput.samplesPerSecond;
    const bytes = soundOutput.bytesPerSample;
    soundOutput.secondaryBufferSize = samples * bytes;
    soundOutput.latencySampleCount = 3 * (samples / gameUpdateHz);
    soundOutput.safetyBytes = (samples * bytes / gameUpdateHz) / 3;
    const bufferSize = soundOutput.secondaryBufferSize;

    win32LoadXinput();
    win32InitDSound(window, soundOutput);
    win32ClearBuffer(&soundOutput);
    check(secondaryBuffer.?.Play(0, 0, sound.DSBPLAY_LOOPING));

    const allocBuffer = allocator.alloc(i16, bufferSize) catch unreachable;
    defer allocator.free(allocBuffer);

    const hdc = win32.graphics.gdi.GetDC(window);

    const gameInput: [2]input.Input = undefined;
    var newInput = gameInput[0];
    var oldInput = gameInput[1];

    _ = win32.media.timeBeginPeriod(1);
    var timer: std.time.Timer = std.time.Timer.start() catch unreachable;
    var gameState = game.GameState{};

    // var debugTimeMarkerIndex: u32 = 0;
    var debugTimeMarkers: [gameUpdateHz / 2]Win32TimeMarker = undefined;
    debugTimeMarkers = std.mem.zeroes(@TypeOf(debugTimeMarkers));

    // var audioLatencyBytes: u32 = 0;
    // var audioLatencyNano: u64 = 0;
    var soundIsValid = false;

    while (globalRunning) {
        const oldKeyboard = &oldInput.controllers[0];
        const newKeyboard = &newInput.controllers[0];
        newKeyboard.* = std.mem.zeroes(input.ControllerInput);
        newKeyboard.connected = true;

        newKeyboard.copyEndedDown(oldKeyboard);
        win32ProcessPendingMessages(newKeyboard);

        if (!globalPause) {
            for (0..@intCast(xbox.XUSER_MAX_COUNT)) |index| {
                const oldController = &oldInput.controllers[index + 1];
                var newController = &newInput.controllers[index + 1];

                var state: xbox.XINPUT_STATE = undefined;
                const success: u32 = @intFromEnum(win32.foundation.ERROR_SUCCESS);
                if (success != xInputGetState(@intCast(index), &state)) continue;

                newController.connected = true;
                const pad = &state.Gamepad;

                const deadZone: f32 = @floatFromInt(xbox.XINPUT_GAMEPAD_LEFT_THUMB_DEADZONE);
                const thumbLX: f32 = @floatFromInt(pad.sThumbLX);
                const thumbLY: f32 = @floatFromInt(pad.sThumbLY);
                newController.stickAverageX = win32ProcessStick(thumbLX, deadZone);
                newController.stickAverageY = win32ProcessStick(thumbLY, deadZone);

                if (newController.stickAverageX != 0.0 or newController.stickAverageY != 0.0) {
                    newController.analog = true;
                }

                if (pad.wButtons & xbox.XINPUT_GAMEPAD_DPAD_UP != 0) {
                    newController.stickAverageY = 1.0;
                    newController.analog = false;
                }

                if (pad.wButtons & xbox.XINPUT_GAMEPAD_DPAD_DOWN != 0) {
                    newController.stickAverageY = -1.0;
                    newController.analog = false;
                }

                if (pad.wButtons & xbox.XINPUT_GAMEPAD_DPAD_LEFT != 0) {
                    newController.stickAverageX = -1.0;
                    newController.analog = false;
                }

                if (pad.wButtons & xbox.XINPUT_GAMEPAD_DPAD_RIGHT != 0) {
                    newController.stickAverageX = 1.0;
                    newController.analog = false;
                }

                const threshold: f32 = 0.5;
                var value: u32 = if (newController.stickAverageX < -threshold) 1 else 0;
                win32ProcessXInputDigitalButton(value, oldController.moveLeft, 1, &newController.moveLeft);

                value = if (newController.stickAverageX > threshold) 1 else 0;
                win32ProcessXInputDigitalButton(value, oldController.moveRight, 1, &newController.moveRight);

                value = if (newController.stickAverageY < -threshold) 1 else 0;
                win32ProcessXInputDigitalButton(value, oldController.moveDown, 1, &newController.moveDown);

                value = if (newController.stickAverageY > threshold) 1 else 0;
                win32ProcessXInputDigitalButton(value, oldController.moveUp, 1, &newController.moveUp);

                win32ProcessXInputDigitalButton(pad.wButtons, oldController.actionDown, //
                    xbox.XINPUT_GAMEPAD_A, &newController.actionDown);
                win32ProcessXInputDigitalButton(pad.wButtons, oldController.actionRight, //
                    xbox.XINPUT_GAMEPAD_B, &newController.actionRight);
                win32ProcessXInputDigitalButton(pad.wButtons, oldController.actionLeft, //
                    xbox.XINPUT_GAMEPAD_X, &newController.actionLeft);
                win32ProcessXInputDigitalButton(pad.wButtons, oldController.actionUp, //
                    xbox.XINPUT_GAMEPAD_Y, &newController.actionUp);

                win32ProcessXInputDigitalButton(pad.wButtons, oldController.leftShoulder, //
                    xbox.XINPUT_GAMEPAD_LEFT_SHOULDER, &newController.leftShoulder);
                win32ProcessXInputDigitalButton(pad.wButtons, oldController.rightShoulder, //
                    xbox.XINPUT_GAMEPAD_RIGHT_SHOULDER, &newController.rightShoulder);

                win32ProcessXInputDigitalButton(pad.wButtons, oldController.start, //
                    xbox.XINPUT_GAMEPAD_START, &newController.start);
                win32ProcessXInputDigitalButton(pad.wButtons, oldController.back, //
                    xbox.XINPUT_GAMEPAD_BACK, &newController.back);
            }

            var buffer: game.ScreenBuffer = .{
                .memory = screenBuffer.memory,
                .width = screenBuffer.width,
                .height = screenBuffer.height,
            };
            game.gameUpdateAndRender(&gameState, newInput, &buffer);

            // const fromBeginToAudioNano = timer.read();

            var playCursor: u32 = 0;
            var writeCursor: u32 = 0;
            check(secondaryBuffer.?.GetCurrentPosition(&playCursor, &writeCursor));

            if (!soundIsValid) {
                soundOutput.runningSampleIndex = writeCursor / bytes;
                soundIsValid = true;
            }

            const byteToLock = (soundOutput.runningSampleIndex * bytes) % bufferSize;
            const expectedSoundBytesPerFrame = (samples * bytes) / gameUpdateHz;
            // const nanoLeftUntilFlip = targetNanoPerFrame - fromBeginToAudioNano;
            // const expectedBytesUntilFlip = nanoLeftUntilFlip / targetNanoPerFrame * expectedSoundBytesPerFrame;

            const expectedFrameBoundaryByte = playCursor + expectedSoundBytesPerFrame;

            var safeWriteCursor = writeCursor;
            if (safeWriteCursor < playCursor) {
                safeWriteCursor += bufferSize;
            }

            std.debug.assert(safeWriteCursor >= playCursor);
            safeWriteCursor += soundOutput.safetyBytes;

            const audioCardIsLowLatency = safeWriteCursor < expectedFrameBoundaryByte;

            var targetCursor: u32 = 0;
            if (audioCardIsLowLatency) {
                targetCursor = expectedFrameBoundaryByte + expectedSoundBytesPerFrame;
            } else {
                targetCursor = (writeCursor + expectedSoundBytesPerFrame +
                    soundOutput.safetyBytes);
            }
            targetCursor = targetCursor % bufferSize;

            var bytesToWrite: u32 = 0;
            if (byteToLock > targetCursor) {
                bytesToWrite = bufferSize - byteToLock;
                bytesToWrite += targetCursor;
            } else {
                bytesToWrite = targetCursor - byteToLock;
            }

            // const fromBeginToAudioSeconds = timer.read();

            var soundBuffer = game.SoundBuffer{
                .samplesPerSecond = @intCast(soundOutput.samplesPerSecond),
                .sampleCount = bytesToWrite / soundOutput.bytesPerSample,
                .samples = allocBuffer.ptr,
            };
            game.getSoundSamples(&gameState, &soundBuffer);
            if (bytesToWrite != 0) {
                win32FillSoundBuffer(&soundOutput, byteToLock, bytesToWrite, &soundBuffer);
            }

            // var marker = &debugTimeMarkers[debugTimeMarkerIndex];
            // debugTimeMarkerIndex += 1;
            // if (debugTimeMarkerIndex >= debugTimeMarkers.len) {
            //     debugTimeMarkerIndex = 0;
            // }

            // marker.playCursor = playCursor;
            // marker.writeCursor = writeCursor;

            // win32DebugSyncDisplay(&screenBuffer, &debugTimeMarkers, &soundOutput);

            win32UpdateWindow(hdc);

            std.mem.swap(input.Input, &oldInput, &newInput);

            const workTime = timer.read();
            std.log.debug("work time: {}", .{workTime});

            std.time.sleep(targetNanoPerFrame -| workTime);
            const delta = timer.lap();
            std.log.debug("frame time: {}, fps: {}", .{ delta, std.time.ns_per_s / delta });
            timer.reset();
        }
    }
}

fn win32ProcessKeyboard(newState: *input.ButtonState, isDown: bool) void {
    newState.endedDown = isDown;
    newState.halfTransitionCount += 1;
}

fn win32ProcessDigital(
    buttonState: u32,
    oldState: *input.ButtonState,
    buttonBit: u32,
    newState: *input.ButtonState,
) void {
    newState.endedDown = ((buttonState & buttonBit) == buttonBit);
    newState.halfTransitionCount = if (oldState.endedDown != newState.endedDown) 1 else 0;
}

fn win32ProcessStick(value: f32, deadZoneThreshold: f32) f32 {
    var result: f32 = 0;
    if (value < -deadZoneThreshold) {
        result = (value + deadZoneThreshold) / (32768.0 - deadZoneThreshold);
    } else if (value > deadZoneThreshold) {
        result = (value - deadZoneThreshold) / (32767.0 - deadZoneThreshold);
    }

    return result;
}

fn win32ProcessPendingMessages(keyboard: *input.ControllerInput) void {
    var message = std.mem.zeroes(win32.ui.windows_and_messaging.MSG);
    const ui = win32.ui.windows_and_messaging;
    while (ui.PeekMessage(&message, null, 0, 0, ui.PM_REMOVE) > 0) {
        switch (message.message) {
            ui.WM_QUIT => globalRunning = false,
            ui.WM_KEYDOWN, ui.WM_KEYUP, ui.WM_SYSKEYDOWN, ui.WM_SYSKEYUP => {
                const wasDown: bool = ((message.lParam & (1 << 30)) != 0);
                const isDown: bool = ((message.lParam & (1 << 31)) == 0);

                if (wasDown == isDown) continue;
                switch (message.wParam) {
                    'W' => win32ProcessKeyboard(&keyboard.moveUp, isDown),
                    'A' => win32ProcessKeyboard(&keyboard.moveLeft, isDown),
                    'S' => win32ProcessKeyboard(&keyboard.moveDown, isDown),
                    'D' => win32ProcessKeyboard(&keyboard.moveRight, isDown),
                    'Q' => win32ProcessKeyboard(&keyboard.leftShoulder, isDown),
                    'E' => win32ProcessKeyboard(&keyboard.rightShoulder, isDown),
                    'P' => {
                        if (isDown) globalPause = !globalPause;
                    },
                    else => {
                        const key = win32.ui.input.keyboard_and_mouse;
                        const wParam: key.VIRTUAL_KEY = @enumFromInt(message.wParam);
                        switch (wParam) {
                            .UP => win32ProcessKeyboard(&keyboard.actionUp, isDown),
                            .LEFT => win32ProcessKeyboard(&keyboard.actionLeft, isDown),
                            .DOWN => win32ProcessKeyboard(&keyboard.actionDown, isDown),
                            .RIGHT => win32ProcessKeyboard(&keyboard.actionRight, isDown),
                            .ESCAPE => win32ProcessKeyboard(&keyboard.start, isDown),
                            .SPACE => win32ProcessKeyboard(&keyboard.back, isDown),
                            else => {},
                        }
                    },
                }
            },
            else => {
                _ = ui.TranslateMessage(&message);
                _ = ui.DispatchMessage(&message);
            },
        }
    }
}

const xbox = win32.ui.input.xbox_controller;
var xInputGetState: *const @TypeOf(xbox.XInputGetState) = undefined;
var xInputSetState: *const @TypeOf(xbox.XInputSetState) = undefined;
fn win32LoadXinput() void {
    if (loader.LoadLibraryW(win32.zig.L("xinput1_4.dll"))) |library| {
        if (loader.GetProcAddress(library, "XInputGetState")) |address| {
            xInputGetState = @ptrCast(address);
        }

        if (loader.GetProcAddress(library, "XInputSetState")) |address| {
            xInputSetState = @ptrCast(address);
        }
    }
}

fn win32ProcessXInputDigitalButton(
    xInputButtonState: u32,
    oldState: input.ButtonState,
    buttonBit: u32,
    newState: *input.ButtonState,
) void {
    newState.endedDown = ((xInputButtonState & buttonBit) == buttonBit);
    const count: u32 = if (oldState.endedDown == newState.endedDown) 0 else 1;
    newState.halfTransitionCount = count;
}

fn check(result: win32.foundation.HRESULT) void {
    if (win32.zig.FAILED(result)) win32ErrorPanic();
}

const Win32SoundOutput = struct {
    samplesPerSecond: u32 = 48000,
    runningSampleIndex: u32 = 0,
    bytesPerSample: u32 = @sizeOf(i16) * 2,
    secondaryBufferSize: u32 = 0,
    safetyBytes: u32 = 0,
    tSine: f32 = 0,
    latencySampleCount: u32 = 0,
};

const sound = win32.media.audio.direct_sound;
var directSoundCreate: *const @TypeOf(sound.DirectSoundCreate) = undefined;
var secondaryBuffer: ?*sound.IDirectSoundBuffer = undefined;
const loader = win32.system.library_loader;
fn win32InitDSound(window: ?win32.foundation.HWND, output: Win32SoundOutput) void {
    if (loader.LoadLibraryW(win32.zig.L("dsound.dll"))) |library| {
        if (loader.GetProcAddress(library, "DirectSoundCreate")) |address| {
            directSoundCreate = @ptrCast(address);
        }
    }
    var directSound: *sound.IDirectSound = undefined;
    check(directSoundCreate(null, @ptrCast(&directSound), null));
    check(directSound.SetCooperativeLevel(window, sound.DSSCL_PRIORITY));

    var bufferDesc = std.mem.zeroes(sound.DSBUFFERDESC);
    bufferDesc.dwSize = @sizeOf(sound.DSBUFFERDESC);
    bufferDesc.dwFlags = sound.DSBCAPS_PRIMARYBUFFER;
    var primaryBuffer: ?*sound.IDirectSoundBuffer = null;

    check(directSound.CreateSoundBuffer(&bufferDesc, &primaryBuffer, null));

    var waveFormat = std.mem.zeroes(win32.media.audio.WAVEFORMATEX);
    waveFormat.wFormatTag = win32.media.audio.WAVE_FORMAT_PCM;
    waveFormat.nChannels = 2;
    waveFormat.nSamplesPerSec = output.samplesPerSecond;
    waveFormat.wBitsPerSample = 16;
    waveFormat.nBlockAlign = (waveFormat.nChannels * waveFormat.wBitsPerSample) / 8;
    waveFormat.nAvgBytesPerSec = waveFormat.nSamplesPerSec * waveFormat.nBlockAlign;
    check(primaryBuffer.?.SetFormat(&waveFormat));

    bufferDesc = std.mem.zeroes(sound.DSBUFFERDESC);
    bufferDesc.dwSize = @sizeOf(sound.DSBUFFERDESC);
    bufferDesc.dwFlags = sound.DSBCAPS_GETCURRENTPOSITION2;
    bufferDesc.dwBufferBytes = output.secondaryBufferSize;
    bufferDesc.lpwfxFormat = &waveFormat;

    check(directSound.CreateSoundBuffer(&bufferDesc, &secondaryBuffer, null));
}

fn win32FillSoundBuffer(
    soundOutput: *Win32SoundOutput,
    offset: u32,
    bytesToWrite: u32,
    soundBuffer: *game.SoundBuffer,
) void {
    var region1: [*]i16 = undefined;
    var region1Size: u32 = 0;
    var region2: [*]i16 = undefined;
    var region2Size: u32 = 0;

    check(secondaryBuffer.?.Lock(offset, bytesToWrite, //
        @ptrCast(&region1), &region1Size, @ptrCast(&region2), &region2Size, 0));

    var source = soundBuffer.samples[0 .. region1Size / 2];
    @memcpy(region1[0 .. region1Size / 2], source);
    const region1SampleCount = region1Size / soundOutput.bytesPerSample;
    for (0..@intCast(region1SampleCount)) |_| {
        soundOutput.runningSampleIndex += 1;
    }

    source = soundBuffer.samples[region1Size / 2 ..][0 .. region2Size / 2];
    @memcpy(region2[0 .. region2Size / 2], source);
    const region2SampleCount = region2Size / soundOutput.bytesPerSample;
    for (0..@intCast(region2SampleCount)) |_| {
        soundOutput.runningSampleIndex += 1;
    }
    check(secondaryBuffer.?.Unlock(region1, region1Size, region2, region2Size));
}

fn win32ClearBuffer(soundOutput: *Win32SoundOutput) void {
    var region1: [*]i16 = undefined;
    var region1Size: u32 = 0;
    var region2: [*]i16 = undefined;
    var region2Size: u32 = 0;

    check(secondaryBuffer.?.Lock(0, soundOutput.secondaryBufferSize, //
        @ptrCast(&region1), &region1Size, @ptrCast(&region2), &region2Size, 0));

    @memset(region1[0 .. region1Size / 2], 0);
    @memset(region2[0 .. region2Size / 2], 0);

    check(secondaryBuffer.?.Unlock(region1, region1Size, region2, region2Size));
}

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

fn createDIBSection() void {
    screenBuffer.deinit();

    screenBuffer.info = std.mem.zeroes(win32.graphics.gdi.BITMAPINFO);
    const biSize = @sizeOf(@TypeOf(screenBuffer.info.bmiHeader));
    screenBuffer.info.bmiHeader.biSize = biSize;
    screenBuffer.info.bmiHeader.biWidth = WIDTH;
    screenBuffer.info.bmiHeader.biHeight = -HEIGHT;
    screenBuffer.info.bmiHeader.biPlanes = 1;
    screenBuffer.info.bmiHeader.biBitCount = 32;
    screenBuffer.info.bmiHeader.biCompression = win32.graphics.gdi.BI_RGB;

    const size: usize = @intCast(WIDTH * HEIGHT * @sizeOf(game.Color));
    screenBuffer.memory = allocator.alloc(game.Color, size) catch unreachable;
}

fn win32UpdateWindow(hdc: ?win32.graphics.gdi.HDC) void {
    const header = screenBuffer.info.bmiHeader;
    const result = win32.graphics.gdi.StretchDIBits(hdc, //
        0, 0, windowWidth, windowHeight, // 目标地址
        0, 0, header.biWidth, -header.biHeight, // 源地址
        screenBuffer.memory.?.ptr, &screenBuffer.info, //
        .RGB_COLORS, win32.graphics.gdi.SRCCOPY);
    if (result == 0) win32ErrorPanic();
}

pub fn mainWindowCallback(
    window: win32.foundation.HWND,
    message: u32,
    wParam: win32.foundation.WPARAM,
    lParam: win32.foundation.LPARAM,
) callconv(std.os.windows.WINAPI) win32.foundation.LRESULT {
    switch (message) {
        win32.ui.windows_and_messaging.WM_SIZE => {
            std.log.info("resize", .{});
            var rect: win32.foundation.RECT = undefined;
            _ = win32.ui.windows_and_messaging.GetClientRect(window, &rect);
            windowWidth = rect.right - rect.left;
            windowHeight = rect.bottom - rect.top;
        },
        win32.ui.windows_and_messaging.WM_CLOSE => globalRunning = false,
        win32.ui.windows_and_messaging.WM_DESTROY => globalRunning = false,
        else => return win32.ui.windows_and_messaging.DefWindowProc(window, message, wParam, lParam),
    }
    return 0;
}

fn win32ErrorPanic() noreturn {
    const err = win32.foundation.GetLastError();
    std.log.err("win32 panic code {}", .{@intFromEnum(err)});
    @panic(@tagName(err));
}
