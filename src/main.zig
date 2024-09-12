const std = @import("std");
const win32 = @import("win32");

pub const UNICODE: bool = true;

const WIDTH: i32 = 640;
const HEIGHT: i32 = 480;

pub fn main() !void {
    var class = std.mem.zeroes(win32.ui.windows_and_messaging.WNDCLASSW);
    class.style = .{ .OWNDC = 1, .HREDRAW = 1, .VREDRAW = 1 };
    class.lpfnWndProc = mainWindowCallback;
    class.hInstance = win32.system.library_loader.GetModuleHandle(null);
    class.lpszClassName = win32.zig.L("Handmade Hero");

    if (win32.ui.windows_and_messaging.RegisterClassW(&class) == 0) {
        return std.log.err("registerClass failed: {}", .{win32.foundation.GetLastError()});
    }

    var style = win32.ui.windows_and_messaging.WS_OVERLAPPEDWINDOW;
    style.VISIBLE = 1;
    const default = win32.ui.windows_and_messaging.CW_USEDEFAULT;
    const window = win32.ui.windows_and_messaging.CreateWindowEx(.{}, //
        class.lpszClassName, win32.zig.L("手工英雄"), //
        style, default, default, WIDTH, HEIGHT, //
        null, null, class.hInstance, null);

    if (window == null) {
        return std.log.err("create window failed: {}", .{win32.foundation.GetLastError()});
    }

    var message = std.mem.zeroes(win32.ui.windows_and_messaging.MSG);
    while (win32.ui.windows_and_messaging.GetMessage(&message, null, 0, 0) > 0) {
        _ = win32.ui.windows_and_messaging.TranslateMessage(&message);
        _ = win32.ui.windows_and_messaging.DispatchMessage(&message);
    }
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
            std.log.info("size", .{});
        },
        win32.ui.windows_and_messaging.WM_DESTROY => {
            std.log.info("destroy", .{});
            win32.ui.windows_and_messaging.PostQuitMessage(0);
        },
        else => return win32.ui.windows_and_messaging.DefWindowProc(window, message, wParam, lParam),
    }
    return 0;
}
