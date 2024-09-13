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

        win32UpdateWindow(hdc);
    }
}

const xbox = win32.ui.input.xbox_controller;
const winapi = std.os.windows.WINAPI;
var xInputGetState: *const fn (u32, *xbox.XINPUT_STATE) callconv(winapi) u32 = undefined;
var xInputSetState: *const fn (u32, *xbox.XINPUT_VIBRATION) callconv(winapi) u32 = undefined;
fn win32LoadXinput() void {
    const loader = win32.system.library_loader;
    if (loader.LoadLibraryW(win32.zig.L("xinput1_4.dll"))) |library| {
        if (loader.GetProcAddress(library, "XInputGetState")) |address| {
            xInputGetState = @ptrCast(address);
        }

        if (loader.GetProcAddress(library, "XInputSetState")) |address| {
            xInputSetState = @ptrCast(address);
        }
    }
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
