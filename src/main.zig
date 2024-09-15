const std = @import("std");
const win32 = @import("win32");
const game = @import("handmade.zig");

pub const UNICODE: bool = true;

var allocator: std.mem.Allocator = undefined;
const WIDTH: i32 = 1280;
const HEIGHT: i32 = 720;

var running: bool = true;
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

    if (window == null) win32ErrorPanic();
    createDIBSection();

    var soundOutput = Win32SoundOutput{};
    const samples = soundOutput.samplesPerSecond;
    const bytes = soundOutput.bytesPerSample;
    soundOutput.secondaryBufferSize = samples * soundOutput.bytesPerSample;
    soundOutput.wavePeriod = @floatFromInt(samples / soundOutput.toneHz);
    soundOutput.latencySampleCount = samples / 15;
    const bufferSize = soundOutput.secondaryBufferSize;

    win32InitDSound(window, soundOutput);
    win32ClearBuffer(&soundOutput);
    const latencyBytes = soundOutput.latencySampleCount * bytes;
    check(secondaryBuffer.?.Play(0, 0, sound.DSBPLAY_LOOPING));

    const allocBuffer = allocator.alloc(i16, bufferSize) catch unreachable;
    defer allocator.free(allocBuffer);

    var message = std.mem.zeroes(win32.ui.windows_and_messaging.MSG);
    const ui = win32.ui.windows_and_messaging;
    var offsetX: usize = 0;
    const hdc = win32.graphics.gdi.GetDC(window);

    while (running) {
        while (ui.PeekMessage(&message, null, 0, 0, ui.PM_REMOVE) > 0) {
            _ = ui.TranslateMessage(&message);
            _ = ui.DispatchMessage(&message);
        }

        offsetX += 1;

        var playCursor: u32 = 0;
        var writeCursor: u32 = 0;
        check(secondaryBuffer.?.GetCurrentPosition(&playCursor, &writeCursor));

        const targetCursor = (playCursor + latencyBytes) % bufferSize;
        const offset: u32 = (soundOutput.runningSampleIndex * bytes) % bufferSize;
        var bytesToWrite: u32 = undefined;
        if (offset > targetCursor) {
            bytesToWrite = bufferSize - offset;
            bytesToWrite += targetCursor;
        } else {
            bytesToWrite = targetCursor - offset;
        }

        var soundBuffer = game.SoundBuffer{
            .samplesPerSecond = soundOutput.samplesPerSecond,
            .sampleCount = bytesToWrite / soundOutput.bytesPerSample,
            .samples = allocBuffer.ptr,
        };

        var buffer: game.ScreenBuffer = .{
            .memory = screenBuffer.memory,
            .width = screenBuffer.width,
            .height = screenBuffer.height,
        };
        game.gameUpdateAndRender(&buffer, offsetX, &soundBuffer, soundOutput.toneHz);

        if (bytesToWrite != 0)
            win32FillSoundBuffer(&soundOutput, offset, bytesToWrite, &soundBuffer);
        win32UpdateWindow(hdc);

        // const delta = timer.lap();
        // std.log.debug("{} us, fps: {}", .{
        //     delta / std.time.ns_per_us,
        //     std.time.ns_per_s / delta,
        // });
    }
}

fn check(result: win32.foundation.HRESULT) void {
    if (win32.zig.FAILED(result)) win32ErrorPanic();
}

const Win32SoundOutput = struct {
    samplesPerSecond: u32 = 48000,
    bytesPerSample: u32 = @sizeOf(i16) * 2,
    secondaryBufferSize: u32 = 0,
    runningSampleIndex: u32 = 0,
    toneHz: u32 = 256,
    toneVolume: f32 = 3000,
    wavePeriod: f32 = 0,
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
        win32.ui.windows_and_messaging.WM_KEYDOWN,
        win32.ui.windows_and_messaging.WM_KEYUP,
        win32.ui.windows_and_messaging.WM_SYSKEYDOWN,
        win32.ui.windows_and_messaging.WM_SYSKEYUP,
        => {
            // if (wParam == @intFromEnum(win32.everything.VK_W))
            //     std.log.debug("W pressed", .{});

            if (wParam == 'W') std.log.debug("W pressed", .{});

            const wasDown: bool = ((lParam & (1 << 30)) != 0);
            const isDown: bool = ((lParam & (1 << 31)) == 0);
            if (wasDown != isDown) {
                if (wParam == 'W') std.log.debug("W down", .{});
            }
        },
        win32.ui.windows_and_messaging.WM_CLOSE => running = false,
        win32.ui.windows_and_messaging.WM_DESTROY => running = false,
        else => return win32.ui.windows_and_messaging.DefWindowProc(window, message, wParam, lParam),
    }
    return 0;
}

fn win32ErrorPanic() noreturn {
    const err = win32.foundation.GetLastError();
    std.log.err("win32 panic code {}", .{@intFromEnum(err)});
    @panic(@tagName(err));
}
