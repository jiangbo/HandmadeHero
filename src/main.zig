const std = @import("std");
const win32 = @import("win32");

pub const UNICODE: bool = true;

const WIDTH: i32 = 640;
const HEIGHT: i32 = 480;
var running: bool = true;

var bitmapInfo: win32.graphics.gdi.BITMAPINFO = undefined;
var bitmapMemory: ?*anyopaque = undefined;
var bitmapHandle: ?win32.graphics.gdi.HBITMAP = undefined;
var bdc: ?win32.graphics.gdi.HDC = undefined;

pub fn main() !void {
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

    var message = std.mem.zeroes(win32.ui.windows_and_messaging.MSG);
    while (running) {
        if (win32.ui.windows_and_messaging.GetMessage(&message, null, 0, 0) > 0) {
            _ = win32.ui.windows_and_messaging.TranslateMessage(&message);
            _ = win32.ui.windows_and_messaging.DispatchMessage(&message);
        }
    }
}

fn resizeDIBSection(width: i32, height: i32) void {
    if (bitmapHandle != null) {
        _ = win32.graphics.gdi.DeleteObject(bitmapHandle);
    }

    if (bdc == null) {
        bdc = win32.graphics.gdi.CreateCompatibleDC(null);
    }

    bitmapInfo = std.mem.zeroes(win32.graphics.gdi.BITMAPINFO);
    bitmapInfo.bmiHeader.biSize = @sizeOf(@TypeOf(bitmapInfo.bmiHeader));
    bitmapInfo.bmiHeader.biWidth = width;
    bitmapInfo.bmiHeader.biHeight = height;
    bitmapInfo.bmiHeader.biPlanes = 1;
    bitmapInfo.bmiHeader.biBitCount = 32;
    bitmapInfo.bmiHeader.biCompression = win32.graphics.gdi.BI_RGB;

    bitmapHandle = win32.graphics.gdi.CreateDIBSection(bdc, //
        &bitmapInfo, .RGB_COLORS, &bitmapMemory, null, 0);
}

const HDC = win32.graphics.gdi.HDC;
fn win32UpdateWindow(hdc: ?HDC, x: i32, y: i32, w: i32, h: i32) void {
    const result = win32.graphics.gdi.StretchDIBits(hdc, //
        x, y, w, h, x, y, w, h, //
        bitmapMemory, &bitmapInfo, //
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
        win32.ui.windows_and_messaging.WM_CREATE => {
            std.log.info("create", .{});
        },
        win32.ui.windows_and_messaging.WM_SIZE => {
            var rect: win32.foundation.RECT = undefined;
            _ = win32.ui.windows_and_messaging.GetClientRect(window, &rect);
            // { .left = 0, .top = 0, .right = 624, .bottom = 441 }
            //  可以看到真实的客户区大小和定义的不一致，因为有边框这些。
            resizeDIBSection(rect.right - rect.left, rect.bottom - rect.top);
        },
        win32.ui.windows_and_messaging.WM_PAINT => {
            var paint: win32.graphics.gdi.PAINTSTRUCT = undefined;
            const hdc = win32.graphics.gdi.BeginPaint(window, &paint);
            defer _ = win32.graphics.gdi.EndPaint(window, &paint);

            const x = paint.rcPaint.left;
            const y = paint.rcPaint.top;
            const width = paint.rcPaint.right - paint.rcPaint.left;
            const height = paint.rcPaint.bottom - paint.rcPaint.top;
            win32UpdateWindow(hdc, x, y, width, height);
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
