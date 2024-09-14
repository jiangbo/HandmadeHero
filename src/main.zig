const std = @import("std");
const win32 = @import("win32");

pub const UNICODE: bool = true;

var allocator: std.mem.Allocator = undefined;
const WIDTH: i32 = 1280;
const HEIGHT: i32 = 720;

var running: bool = true;
var windowWidth: i32 = 0;
var windowHeight: i32 = 0;
var screenBuffer: win32ScreenBuffer = undefined;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    allocator = gpa.allocator();

    createWindow();
    screenBuffer.deinit();
}

const win32ScreenBuffer = struct {
    info: win32.graphics.gdi.BITMAPINFO = undefined,
    memory: ?[]Color = null,
    width: i32 = WIDTH,
    height: i32 = HEIGHT,
    pitch: i32 = 0,

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
    win32LoadXinput();

    win32InitDSound(window, 2);
    check(secondaryBuffer.?.Play(0, 0, sound.DSBPLAY_LOOPING));

    var message = std.mem.zeroes(win32.ui.windows_and_messaging.MSG);
    const ui = win32.ui.windows_and_messaging;
    var offsetX: usize = 0;
    const hdc = win32.graphics.gdi.GetDC(window);
    while (running) {
        while (ui.PeekMessage(&message, null, 0, 0, ui.PM_REMOVE) > 0) {
            _ = ui.TranslateMessage(&message);
            _ = ui.DispatchMessage(&message);
        }

        for (0..@intCast(xbox.XUSER_MAX_COUNT)) |index| {
            var state: xbox.XINPUT_STATE = undefined;
            const success: u32 = @intFromEnum(win32.foundation.ERROR_SUCCESS);
            if (success != xInputGetState(@intCast(index), &state)) {
                continue;
            }

            const up = state.Gamepad.wButtons & xbox.XINPUT_GAMEPAD_DPAD_UP;
            if (up != 0) std.log.debug("up", .{});
            // const Down = state.Gamepad.wButtons & xbox.XINPUT_GAMEPAD_DPAD_DOWN;
            // const Left = state.Gamepad.wButtons & xbox.XINPUT_GAMEPAD_DPAD_LEFT;
            // const Right = state.Gamepad.wButtons & xbox.XINPUT_GAMEPAD_DPAD_RIGHT;
            // const Start = state.Gamepad.wButtons & xbox.XINPUT_GAMEPAD_START;
            // const Back = state.Gamepad.wButtons & xbox.XINPUT_GAMEPAD_BACK;
            // const LeftShoulder = state.Gamepad.wButtons & xbox.XINPUT_GAMEPAD_LEFT_SHOULDER;
            // const RightShoulder = state.Gamepad.wButtons & xbox.XINPUT_GAMEPAD_RIGHT_SHOULDER;
            // const A = state.Gamepad.wButtons & xbox.XINPUT_GAMEPAD_A;
            // const B = state.Gamepad.wButtons & xbox.XINPUT_GAMEPAD_B;
            // const X = state.Gamepad.wButtons & xbox.XINPUT_GAMEPAD_X;
            // const Y = state.Gamepad.wButtons & xbox.XINPUT_GAMEPAD_Y;

            // const stickX = state.Gamepad.sThumbLX;
            // const stickY = state.Gamepad.sThumbLY;
        }

        renderWeirdGradient(offsetX, 0);
        offsetX += 1;

        var runningSampleIndex: u32 = 0;
        var playCursor: u32 = undefined;
        var writeCursor: u32 = undefined;

        check(secondaryBuffer.?.GetCurrentPosition(&playCursor, &writeCursor));

        const bufferSize = 2 * samplesPerSecond * bytesPerSample;
        const byteToLock: u32 = runningSampleIndex * bytesPerSample % bufferSize;
        var bytesToWrite: u32 = 0;
        if (byteToLock == playCursor) {
            bytesToWrite = bufferSize;
        } else if (byteToLock > playCursor) {
            bytesToWrite = bufferSize - byteToLock;
            bytesToWrite += playCursor;
        } else {
            bytesToWrite = playCursor - byteToLock;
        }

        var region1: [*]i16 = undefined;
        var region1Size: u32 = 0;
        var region2: [*]i16 = undefined;
        var region2Size: u32 = 0;
        check(secondaryBuffer.?.Lock(byteToLock, bytesToWrite, //
            @ptrCast(&region1), &region1Size, @ptrCast(&region2), &region2Size, 0));

        const toneHz = 256;
        const squareWavePeriod = samplesPerSecond / toneHz;
        const halfSquareWavePeriod = squareWavePeriod / 2;
        const toneVolume = 3000;

        var sampleOut = region1;
        const region1SampleCount = region1Size / bytesPerSample;
        for (0..@intCast(region1SampleCount)) |_| {
            const value = (runningSampleIndex / halfSquareWavePeriod) % 2;
            const sampleValue: i16 = if (value == 0) toneVolume else -toneVolume;
            runningSampleIndex += 1;

            sampleOut[0] = sampleValue;
            sampleOut[1] = sampleValue;
            sampleOut += 2;
        }

        sampleOut = region2;
        const region2SampleCount = region2Size / bytesPerSample;
        for (0..@intCast(region2SampleCount)) |_| {
            const value = (runningSampleIndex / halfSquareWavePeriod) % 2;
            const sampleValue: i16 = if (value == 0) toneVolume else -toneVolume;
            runningSampleIndex += 1;

            sampleOut[0] = sampleValue;
            sampleOut[1] = sampleValue;
            sampleOut += 2;
        }
        check(secondaryBuffer.?.Unlock(region1, region1Size, region2, region2Size));

        win32UpdateWindow(hdc);
    }
}

const xbox = win32.ui.input.xbox_controller;
var xInputGetState: *const @TypeOf(xbox.XInputGetState) = undefined;
var xInputSetState: *const @TypeOf(xbox.XInputSetState) = undefined;
const loader = win32.system.library_loader;
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

fn check(result: win32.foundation.HRESULT) void {
    if (win32.zig.FAILED(result)) win32ErrorPanic();
}

const samplesPerSecond: u32 = 48000;
const bytesPerSample: u32 = @sizeOf(i16) * 2;
const sound = win32.media.audio.direct_sound;
var directSoundCreate: *const @TypeOf(sound.DirectSoundCreate) = undefined;
var secondaryBuffer: ?*sound.IDirectSoundBuffer = undefined;
fn win32InitDSound(window: ?win32.foundation.HWND, seconds: u32) void {
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
    waveFormat.nSamplesPerSec = samplesPerSecond;
    waveFormat.wBitsPerSample = 16;
    waveFormat.nBlockAlign = (waveFormat.nChannels * waveFormat.wBitsPerSample) / 8;
    waveFormat.nAvgBytesPerSec = waveFormat.nSamplesPerSec * waveFormat.nBlockAlign;
    check(primaryBuffer.?.SetFormat(&waveFormat));

    bufferDesc = std.mem.zeroes(sound.DSBUFFERDESC);
    bufferDesc.dwSize = @sizeOf(sound.DSBUFFERDESC);
    bufferDesc.dwBufferBytes = seconds * samplesPerSecond * bytesPerSample;
    bufferDesc.lpwfxFormat = &waveFormat;

    check(directSound.CreateSoundBuffer(&bufferDesc, &secondaryBuffer, null));
}

const Color = extern struct { b: u8 = 0, g: u8 = 0, r: u8 = 0, a: u8 = 0 };

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

    const size: usize = @intCast(WIDTH * HEIGHT * @sizeOf(Color));
    screenBuffer.memory = allocator.alloc(Color, size) catch unreachable;
}

fn renderWeirdGradient(offsetX: usize, offsetY: usize) void {
    const w: usize = @intCast(WIDTH);
    for (0..@as(usize, @intCast(HEIGHT))) |y| {
        for (0..w) |x| {
            screenBuffer.memory.?[x + y * w] = .{
                .b = @truncate(x + offsetX),
                .g = @truncate(y + offsetY),
            };
        }
    }
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
